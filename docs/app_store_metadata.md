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
