# JeniFit — App Store Metadata Draft

For App Store Connect submission of v1.0.0. The voice intentionally
lands a notch more conventional than the in-app italic-Fraunces
JeniFit voice — App Store renders plain text, and reviewers / users
scanning rapidly need clear positioning before anything more
editorial. Punch words land via paragraph rhythm + selective
capitalization, not asterisks.

All numbers below are within Apple's character limits. Verify in
App Store Connect before submitting.

---

## App name

`JeniFit`

(Display name, as set by `CFBundleDisplayName` in `Info.plist`.)

## Subtitle (30 char max)

```
calm, smart, at-home fitness
```

(28 chars including spaces.)

Alternatives if "calm, smart" reads off:

- `your home fitness, simplified` (29)
- `become her, one day at a time` (29)
- `science-led at-home workouts` (28)

## Promotional text (170 char max — editable post-submission)

```
The fitness app for women who want to feel strong, not pressured. Daily workouts adapt to your body, your tier, and your time. No shouty trainers. No shame.
```

(155 chars. The "no shouty trainers, no shame" closer is positioning
against the typical louder fitness-app marketing.)

## Description (4,000 char max)

```
JeniFit is the fitness app for women who want to feel strong, not pressured.

Every day you get one workout — built around your body focus, your experience level, and the time you actually have. No app-of-the-month gimmicks. No before-and-after shaming. Just the work, laid out clearly.

WHAT MAKES IT DIFFERENT

• Workouts that adapt to you, not the other way around
The plan calibrates from your onboarding answers — your goal area, your activity baseline, even how long you can hold a plank. As you log sessions, the engine learns: an "easy" rating bumps difficulty up, a "too hard" rating dials it back. You're never stuck on a plan that no longer fits.

• Real research, no fitness pseudoscience
Exercises are selected from a 128-move library using published evidence: Stuart McGill's core endurance norms, the ACSM 150–300 min/week target, Pamela Reif and growingannanas structural patterns. We don't promise "burn fat fast." We tell you what each move does and why we picked it.

• On-device form check
For plank sessions, your camera watches your alignment in real time. Frames are processed by Apple's Vision framework on your phone. Nothing is recorded. Nothing leaves your device. Your coach calls out hip sag or shoulder creep before they become habits.

• Three coaching voices
Pick the trainer who sounds like the support you actually want — Jeni (mindful and calm), Kira (sassy and direct), or Sam (chill and supportive). Same workouts, different energy.

• Becoming, not punishing
The progress tab pulls from data you already gave us at signup — what you said you wanted, why you started, the barriers you named. So when you've shown up four times this week, we don't just say "+4 sessions." We say "you said motivation was hard — you've shown up four days." That's the loop.

• Weight tracking that respects you
One log per day (research backs this — multiple weigh-ins per day correlate with anxiety, not better outcomes). BMI, goal pace, and weekly trend, with an ED-safe one-tap option to hide all numbers. You can keep tracking silently if that's what works.

WHAT YOU GET

• Daily personalized workouts (5–45 min)
• Plank check-in with on-device form coaching
• Weight + BMI + activity tracking
• Streak system with auto-freeze (one missed day doesn't reset you)
• Identity-driven progress reflections — adaptive to your stated goals + barriers
• Three coach voices, with audio cues mixed under your background music
• Daily reminder at the time you pick

PRIVACY

We don't sell your data. We don't run advertising trackers. The only third parties we use are Supabase (database), Apple (Sign in with Apple), and RevenueCat (subscription state) — all named in our privacy policy. Camera frames stay on your phone.

SUBSCRIPTION

JeniFit offers a free trial, then auto-renews unless you cancel in iOS Settings. Pricing is shown in-app at checkout. You can restore purchases or delete your account anytime from Settings.

QUESTIONS

support@jenifit.app

privacy: jenifit.app/privacy
terms: jenifit.app/terms
```

(2,683 chars. Plenty of room to expand if needed.)

## Keywords (100 char max, comma-separated)

```
fitness,workout,home workout,plank,abs,glutes,women,weight loss,coach,trainer,bmi,form
```

(91 chars. Each keyword is comma-separated; no spaces after commas
because Apple's parser counts them. Ordering matters — earlier
keywords get more weight.)

**Why these:** ranked by likely conversion vs. competition:

- `fitness` / `workout` — broad, expensive but relevant
- `home workout` — high-intent searcher, what we are
- `plank` / `abs` / `glutes` — body-focus terms our engine targets
- `women` — primary demographic
- `weight loss` — onboarding-stated motivation
- `coach` / `trainer` — the voice-coaching feature
- `bmi` / `form` — the becoming-tab + plank-check features

**Skipped on purpose:**

- `AI` / `AI coach` — the rules doc + CLAUDE.md flag this language; we don't use it.
- `ozempic` / `wegovy` / brand-name diet drugs — risky and off-brand.
- `weight tracker` / `bmi calculator` — too narrow; users searching those probably aren't fitness-app shoppers.

## Promotional text variants

If conversion testing shows the main promo isn't landing, try:

- `Workouts that calibrate to your body, your tier, your time. On-device form coaching for plank. Three coach voices. No shame.` (130)
- `One personalized workout a day. Built on McGill, ACSM, and Pamela Reif's structural patterns — not vibes. Free trial inside.` (124)
- `She's already in you. We just hand you the schedule. Calm, science-led at-home fitness for women who don't want a drill sergeant.` (134)

## What's New — v1.0.0

```
Welcome to JeniFit v1.0.

Daily workouts that adapt to your goals, your tier, and the time you actually have. On-device plank form check. Weight + BMI tracking with one-per-day logging. Three coach voices. The becoming tab — your progress reflected back through the answers you gave us.

We hope it feels like working out with a friend who pays attention.

— The JeniFit team
```

(396 chars.)

## Category

Primary: **Health & Fitness**
Secondary: **Lifestyle**

(Set in App Store Connect; the `LSApplicationCategoryType` in
`Info.plist` is already `public.app-category.healthcare-fitness`.)

## Screenshots

Per TODOS.md — captured separately from the simulator at the three
required device sizes (6.7", 6.5", 5.5"). Suggested order:

1. Welcome + sticker scatter (Phase 15b hero) — visual identity
2. Home with daily workout card + mindful subtitle — what users do daily
3. Plank check-in setup (PreSessionView) — research-led + on-device form coach
4. Active session view — timer + position cue + meta line
5. Becoming tab hero + identity hero — research-grounded reflection
6. Becoming tab WHO Activity Ring + weight trend — measurable progress
7. Becoming tab Barrier-Resolved Card — adaptivity proof
8. Coach picker (ChangeTrainerView) — three voices

Each caption stays in JeniFit voice (lowercase, italic punch — even
though App Store doesn't render italic, the lowercasing is
on-brand).

## Reviewer notes (App Store Connect → App Review Information)

```
Tester credentials: leave blank. The app supports anonymous use; reviewers can complete onboarding and reach the full app without signing in.

Camera permission is requested on the plank check-in pre-session screen, not at app launch. Frames are processed on-device by Apple's Vision framework — never recorded, never uploaded. The pre-permission screen explains this verbatim.

Subscription pricing is configured via the absmaxxing.storekit StoreKit Configuration File for sandbox testing; production pricing reads from the App Store's IAP entries.

Privacy policy: https://jenifit.app/privacy
Terms of service: https://jenifit.app/terms
Support email: support@jenifit.app

The app collects health-adjacent data (weight, body type, BMI). It is not a medical device. The in-app health disclaimer in Settings → Account is verbatim from our terms of service.
```

---

# v1.1.7 FINAL — the ASC field set (2026-08-08, expert-panel synthesis)

Supersedes the draft section below it. Produced by an ASO + healthcare
compliance + conversion-copy panel over the founder's draft; every
count machine-verified; ban sweep clean (no "AI", no drug names, no
numeric promises, no fasting vocabulary, no trial language, no
fabricated proof). Brand is **Jeni** per the founder (aligns the
store with Jeni Health › Jeni Care › Jeni and the on-device display
name; the rename lands with this submission).

## Name (27/30)

```
Jeni: Weight Loss for Women
```

Alt A (action phrase): `Jeni: Lose Weight for Women` (27). Alt B
(positioning): `Jeni: Weight Loss Coach` (23).

## Subtitle (29/30)

```
Calorie Counter, Food Scanner
```

## Keywords (99/100)

```
tracker,macro,protein,diet,barcode,glp,carb,meal,log,diary,photo,coach,plan,noise,fat,scale,jenifit
```

Notes: `weight/loss/women` live in the Name and `calorie/counter/
food/scanner` in the Subtitle — never duplicated in the field.
`fasting` is banned (no feature; Apple 2.3.7 + project law) — its
slot funds `barcode`. `jenifit` preserves brand-search continuity
after the rename (no longer the app name, so the self-name rule no
longer bars it). `noise` composes "food noise" with the subtitle —
the GLP-1-era wedge the lessons literally teach. Variant: swap
`scale` for `label` if label-scan queries outperform.

## Promotional text (three options, rotate without review)

1. Launch (152): `The food scanner, rebuilt. Photo, barcode, or nutrition label. One clear page you can edit. A food diary your photos lead. Quieter, faster, more honest.`
2. Evergreen (141): `Snap your meal, scan a barcode, or photograph the label. Honest numbers, a plan that fits how you actually live, and a coach who never yells.`
3. Evergreen (154): `Weight bounces. Jeni shows the trend, not the daily number. A plan built from your answers, a coach who reads your real data, and no shame anywhere in it.`

## Description (2,844/4,000 — B2C-first, clinic-credible: "clinical
guidance" pacing, plain-words coach framing, clinician-compatibility
in the inclusion list, and the clinician-referral disclaimer; nothing
promises a clinic product)

```
Jeni is the calm weight-loss coach for women. Snap a meal, scan a barcode, or photograph the label. Calories and macros in seconds, and a plan that's actually yours.

No crash diets. No calorie math in your head. No shouty trainers, no before-and-after shame. Just a steady plan that adapts to how you really eat and live.

SNAP YOUR FOOD, SKIP THE GUESSWORK
Point your camera at any meal and get calories, protein, carbs, fat, fiber, and sugar before you pick up your fork. Packaged food? Scan the barcode or photograph the nutrition label. It all comes back as one clean page. Ate about half? Adjust any item in a tap. Every plate lands in your food diary, photos first, so you see the whole week, not just one number.

A PLAN THAT'S ACTUALLY YOURS
Your plan is built from your answers: your goal, your pace, your body. It's paced to clinical guidance, not a deadline, and it adapts as you go, so you're never stuck in someone else's week.

A COACH IN YOUR POCKET
Meet jeni, your coach. Ask her anything: what to eat, how to hit your protein, why the scale jumped. She reads your real data and answers in plain words, with the science underneath.

THE TREND, NOT THE DAILY NUMBER
Weight bounces. Jeni shows your trend line, so one heavy morning never derails you. Log a weigh-in and watch the direction, gently.

MORE THAN A TRACKER
- Protein and macro targets that fit your body
- Short lessons that quiet food noise and rebuild your relationship with food
- Breathwork for the stressed, snacky moments
- Steps and sleep, synced from Apple Health
- Quiet, private insights from the data you already have

BUILT FOR WHERE YOU ARE
Just starting, stuck at a plateau, or keeping off what you've already lost? On a GLP-1 journey or not, working with a clinician or on your own, Jeni meets you there, with a plan you can actually keep.

Your becoming starts today.

YOUR DATA, YOURS
Your health data is never sold and never used for advertising. Meal photos are analyzed to estimate nutrition, and you can turn photo keeping off. Body scans never leave your phone unless you say so. Full policy at jenifit.app/privacy.

Jeni supports everyday food, movement, and weight habits. It isn't medical advice and doesn't diagnose or treat any condition. For decisions about your health or medication, talk with your clinician.

Membership unlocks your full plan, your coach, and every feature. Plans are yearly, quarterly, or weekly, with prices shown in the app before you buy. Payment is charged to your Apple Account at confirmation of purchase, and your plan auto-renews unless cancelled at least 24 hours before the current period ends. Manage or cancel anytime in your App Store account settings. You can restore purchases in the app.

Terms of Use: https://jenifit.app/terms
Privacy Policy: https://jenifit.app/privacy
Support: support@jenifit.app
```

## What's New — 1.1.7 (432/4,000)

```
The food experience, rebuilt from the ground up.

- A new scanner: snap your plate, scan a barcode, or photograph the nutrition label.
- One clear page for every result: calories, protein, and macros together. Tap any item to edit it, and the math follows.
- A redesigned food diary: your photos lead, so your week reads like a journal, not a spreadsheet.

Under it all: quieter, faster, more honest.

Same calm coach, better tools.
```

## Remaining fields

- Support URL: `https://jenifit.app/support` — **verify the page is
  live before submitting** (dead support links are a rejection; only
  /privacy and /terms were confirmed live in the audit).
- Marketing URL: `https://jenifit.app`
- Version: `1.1.7` (matches MARKETING_VERSION; the store train
  continues from 1.1.6 — 1.2.0 never shipped).
- Copyright: `© 2026 bay82 Studio LLC`
- Reviewer notes: use the block in the draft section below (accurate
  to the shipped v23 product; anonymous-first, camera/barcode demo
  paths, ATT placement, pay-upfront, deletion path).

---

# v1.1.7 — the still-life era metadata (2026-08-08)

Written for the shipped v23 product (SnapDial food experience, THE
BOOK, Body Vision, the day plan, jeni's letters). Supersedes every
section below for ASC fields. Laws honored: no "AI", no drug brand
names, no numeric weight-loss promises, no trial language (the app is
pay-upfront), bodies reference shipping features only. FOUNDER: paste
into ASC, recapture screenshots (6.9" + 6.5"/6.7"), and replace the
reviewer notes — the v1.0.0 notes below describe the retired plank
camera and must not be reused.

## App name / subtitle

Display name is `Jeni` (CFBundleDisplayName). ASC store name currently
"JeniFit: Lose Weight" — founder decision: keep for search continuity
or move to "Jeni: Weight Loss & Food". Subtitle candidate (30 max):

```
the calm weight-loss program
```

(28 chars.)

## Promotional text (170 max)

```
point the camera at your plate and get honest numbers. a day plan that fits your real life, a food journal that reads like yours. made for women, paced for you.
```

(159 chars.)

## Description (4,000 max)

```
Jeni is the weight-loss program that doesn't yell at you.

Point the camera at your plate and get honest numbers — calories with a range, protein against your floor, and a plain reading of what's on the plate. Scan a barcode for packaged food. Photograph a nutrition label. Or just write what you ate. One page, no scores, no shame.

THE FOOD CAMERA
Snap a plate and watch the reading assemble: counted calories, your protein floor, the plate's split, and a line from jeni that actually says something. Edit any item — portions, additions, swaps — and the math stays coherent. Every meal files itself into your book.

THE BOOK
Your food journal, kept like a journal — day spreads with your photographs leading, weeks that read honestly, months with real seams. Log a meal again in two taps.

THE DAY, COMPOSED
One checklist, built each morning from your answers: your meals, your movement, your weigh-in cadence, your medication rhythm if you have one. Days flex when your week does. Nothing guilts you.

YOUR TREND, NOT TODAY'S NUMBER
Weight arrives passively from Apple Health when you allow it. The chart shows the trend that matters, never just this morning's number. An option hides every number if numbers aren't kind to you.

YOUR BODY, PRIVATELY
Guided body scans stay on your phone — processed on-device into quiet ink silhouettes. No number is ever derived from a photo. Backup is off unless you turn it on.

BECOMING
Protein, fiber, sugar intake, sodium, sleep, steps — each with its own honest chart and a plain explanation of what the plan does about it.

JENI
Write to jeni anytime. She answers in plain language, knows your plan, and never performs enthusiasm.

PRIVACY
Your health data is never sold and never used for advertising. Meal photos are analyzed to estimate nutrition, and you can turn photo keeping off. Body scans never leave your phone unless you say so. Full policy: jenifit.app/privacy

SUBSCRIPTION
Jeni is a paid program: yearly, quarterly, or weekly auto-renewing plans, priced in-app at checkout. Cancel anytime in iOS Settings. Restore purchases and account deletion live in Settings.

QUESTIONS
support@jenifit.app
privacy: jenifit.app/privacy
terms: jenifit.app/terms
```

(~2,050 chars.)

## Keywords (100 max)

```
calorie,counter,tracker,weight,loss,food,scanner,barcode,diet,meal,log,plan,women,macro,photo
```

(95 chars. v1.0.9 set + `barcode`; "fitness" stays out — lives in
category; "AI" and drug-brand terms stay banned.)

## What's New — v1.1.7

```
the food experience, rebuilt from zero.

• point the camera and the dial reads your plate — photo, barcode, or nutrition label
• the reading: one honest page — calories with a range, your protein floor, the plate's split, editable items
• the book: your food journal as day spreads, photographs leading, weeks that read honestly
• log any meal again in two taps
• a cleaner home: your day's numbers up front, your tasks as real objects

quieter, faster, more honest. that's the whole idea.
```

(~470 chars.)

## Reviewer notes (App Review Information)

```
Tester credentials: leave blank. The app is anonymous-first; complete onboarding and reach the full app without creating an account. Sign-in (Apple/email) is optional.

Food camera: point at any plate of food (or a photo of food on another screen) to get a nutrition reading. Barcode mode reads packaged-food barcodes live. Label mode photographs a nutrition-facts panel. Photos are analyzed by our server function; a small thumbnail is kept with the journal unless the user disables photo keeping in Settings → privacy.

Body scans: guided camera flow, processed on-device. Photos stay on the device unless the user enables backup (off by default). No numeric estimate is ever produced from a photo.

HealthKit: reads steps, sleep, and body weight to compose the daily plan and the trend chart; can write logged nutrition with permission. Health data is not used for advertising.

App Tracking Transparency: the prompt appears during onboarding's plan-loading step. Denying tracking changes nothing about app functionality.

Subscriptions: yearly / quarterly / weekly auto-renewing, purchased after onboarding (pay-upfront, no trial). Restore Purchases is on the paywall and in Settings. Account deletion: Settings → account → delete account (server-side cascade).

Privacy policy: https://jenifit.app/privacy
Terms: https://jenifit.app/terms
Support: support@jenifit.app
```

## Screenshots

Spec must be recaptured from v23 UI (docs/APP_STORE_SCREENSHOTS.md is
v1.0-era and stale). Suggested order: 1) the reading (hero) 2) the
dial over a plate 3) the book day spread 4) home with the hero
carousel 5) becoming trend 6) jeni's letter. Founder captures at
6.9" (1320×2868) + 6.7" (1290×2796).

---

# v1.0.9 — program-era metadata (2026-06-12)

Product pivoted to a custom weight-loss program (food camera + daily
ritual). This supersedes the v1.0.0 workout-first copy above for ASC
fields. Voice rules honored: no "AI", no em-dashes, post-Ozempic
vocabulary, no fabricated stats, anti-shame framing.

## Promotional text (147/170)

```
the weight loss app that doesn't yell at you. snap a photo, get the calories. a daily plan that fits your real life. made for women, paced for you.
```

## Keywords (93/100)

```
calorie,counter,tracker,weight,loss,food,scanner,diet,meal,log,plan,women,macro,photo,workout
```

Apple cross-combines: calorie counter, calorie tracker, weight loss,
food scanner, food log, meal plan, diet plan, macro tracker, weight
tracker, photo calorie. "fitness" dropped (lives in the subtitle; a
keyword may never repeat title/subtitle words). Drug-brand terms +
"AI" still skipped on purpose.

## Description + What's New

See ASC submission 2026-06-12 (full texts delivered in-session;
description 2,905 chars, what's new 1,431 chars, both with
privacy/terms/support links + Apple subscription disclosure).
