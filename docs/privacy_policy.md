<!-- FOUNDER / DEPLOY NOTE (updated 2026-08-19)
     This file is the iOS-side source of truth. The URL the app actually
     links to (PaywallView, SignUpView, DownsellPaywallView,
     SmallerStepSheet all point at https://jenifit.app/privacy) is
     rendered from a DIFFERENT repository: /Users/bko/jenifit-web
     (src/app/privacy/page.tsx). That live page is still describing
     app v1.1.4 and states "No advertising trackers, no data brokers"
     while the shipped binary links the TikTok Business SDK with real
     production credentials and declares NSPrivacyTracking = true.

     That contradiction is the single highest App Review + regulatory
     risk in the legal surface and CANNOT be fixed from this repo.
     Port this document to jenifit-web BEFORE the next submission and
     re-answer the App Store Connect privacy nutrition label to match
     (tracking = YES via TikTok; health & fitness linked to identity).

     Counsel review recommended, in particular on: the HIPAA paragraph,
     the clinic-connected ("your care team") section, and whether the
     TikTok ad-measurement flow is "sharing" under CCPA/CPRA.

     STILL UNRESOLVED (founder input required): bay82 Studio LLC's
     business mailing address, and whether the GitHub repository
     holding TikTokAppConfig.appSecret is public. -->

# Jeni Privacy Policy

**Effective:** 2026-05-08
**Last updated:** 2026-08-19
**App version:** 1.2.0

Jeni (formerly JeniFit) is a weight-care app for iOS, provided by
**bay82 Studio LLC** ("we", "us"). This policy explains what we
collect, why, where it's stored, who can see it, and how to delete it.
We aimed for plain language. If something's unclear, email
[support@jenifit.app](mailto:support@jenifit.app).

## TL;DR

- **Your account works anonymously.** You can use the whole app
  without giving us an email; sign-in (Apple or email) is optional and
  exists so your data can follow you to a new phone.
- **Meal photos you snap** are sent to our server function and
  analyzed by OpenAI's vision model to estimate nutrition. The
  full-size photo is processed and discarded; a small thumbnail is
  kept with your food journal, on your device and in your private
  cloud space, unless you turn that off in Settings → privacy.
- **Body scan photos never leave your phone** unless you explicitly
  turn on scan backup (off by default). No number is ever derived
  from a body photo.
- **Apple Health is read-only, and one thing crosses over.** We read
  more than steps: sleep, workouts, distance, active energy, resting
  heart rate, heart-rate variability, body composition, cycle timing,
  and body weight, all only with your permission. Everything is used
  on-device to run your plan and stays there, with one exception:
  **weigh-ins imported from Apple Health are saved to your Jeni
  account** like a weigh-in you typed yourself. We never sell any of
  it and never send any of it to advertising partners.
- **Your weight-care record syncs to your account.** Weigh-ins, food
  logs, medication and dose marks, and how you felt (side effects and
  symptoms) are stored in your private cloud rows so they survive a
  new phone.
- **We use analytics and ad attribution.** PostHog measures how the
  app is used (screens, funnel steps, purchases, never your meals,
  weights, messages, or photos). The TikTok Business SDK reports
  install and purchase events so we can measure our ads; it can only
  use your device's advertising identifier if you allow tracking in
  the iOS prompt.
- **A clinic sees nothing unless you connect one.** If you enter a
  clinic invite code and grant consent, selected parts of your record
  go to that practice. Off by default, revocable anytime. See "Your
  care team" below.
- **Delete everything anytime.** Settings → account → delete account
  removes your cloud rows, your photos, and your local data.

## What we collect

### From your device

- **Food camera.** Photos you take of meals, sent over TLS to our
  server function for nutrition analysis (see "Meal photos"). Barcode
  scanning happens on-device; the barcode number is looked up against
  the Open Food Facts database. Nutrition-label photos are analyzed
  the same way meal photos are.
- **Body scan camera.** Guided scans are processed on-device by
  Apple's Vision framework into ink silhouettes. Photos and
  silhouettes are stored only on your phone (excluded from device
  backups, location metadata stripped) unless you turn on the
  optional cloud backup. We never estimate weight, body fat, or any
  number from a photo.
- **Microphone:** none. **Location:** none. **Photo library:** we
  never read your library; if you save a share card, iOS asks for
  add-only permission.

### Apple Health (HealthKit)

We request **read-only** access to the categories below, and iOS lets
you grant or deny each one. We only ever see what you allow:

| What we read | What it's for |
| --- | --- |
| Steps, walking/running distance, active energy, workouts | Your movement rail and weekly read |
| Sleep analysis | Pacing your plan honestly |
| Body weight | Passive weigh-in import and your trend chart |
| Body fat %, lean body mass | Composition, only if a smart scale already writes it |
| Resting heart rate, heart-rate variability | The recovery line in your weekly read |
| Menstrual flow | The "season" signal, so your plan expects a normal scale bump |

Two things are worth stating plainly, because a general "Health data
stays on your device" claim would not be accurate:

- **Weigh-ins imported from Apple Health are saved to your Jeni
  account.** That is the whole point of passive import: your trend
  chart has to survive a reinstall. They become ordinary weight rows
  in your private cloud space, identical to ones you type in.
- **Everything else stays on-device.** Steps, sleep, workouts,
  distance, energy, heart-rate data, composition, and cycle timing
  are read on-device to compose your day and your weekly read. Those
  values are not uploaded to our servers.

**Writing back:** off by default. If you turn on the Apple Health
write toggle in food settings, the meal calories you log are written
to Apple Health as Dietary Energy. Nothing else is ever written.

Apple Health data is never used for advertising and is never shared
with advertising partners. You can revoke any category at any time in
iOS Settings → Privacy & Security → Health → Jeni.

### Meal photos

When you snap a plate (or a nutrition label), the photo is sent to our
secure server function, which passes it to OpenAI's vision model to
estimate the meal's nutrition. Under our API agreement OpenAI does not
use your photos to train its models. What we keep afterward:

- **A small thumbnail** (long edge capped at 480px, not the full
  camera frame) is stored with the journal entry on your device and
  uploaded to your private space in our cloud storage, so your meal
  photos come back when you reinstall or switch phones. The full-size
  photo is not stored.
- **You can turn photo keeping off.** Settings → privacy → photo
  retention: choose "discard after analysis" and no photo is saved to
  your journal or uploaded, only the nutrition estimate is kept.
- **Access is per-account.** The storage bucket is private, and access
  rules enforce that only your signed-in account can read, write, or
  delete objects under your own folder.
- **Deleting follows you everywhere.** Deleting a journal entry
  removes its thumbnail from your device and from cloud storage;
  deleting your account removes all of your meal photos.
- We never use your photos for advertising, never share them with
  other users, and never train models on them.

### From you, as you use the app

What you tell us during onboarding and day-to-day. Categories:

| Data | Why | Synced to your account? |
| --- | --- | --- |
| Name (first, optional) | Greeting + personalization | Yes |
| Age range, gender, height | Calorie targets and pacing (published equations) | Yes |
| Weight logs (current, goal, history, typed or imported from Apple Health) | Trend chart, goal pace, plan recalibration | Yes |
| Medication and dose record (which weight medication, dose, schedule, and whether you marked a dose taken or skipped) | Composing your day around your medication rhythm; protein and muscle-preservation targets | Yes |
| How you felt (side effects, symptoms, tolerability notes) | Pacing the plan; the summary you bring to a visit | Yes |
| Safety screening answers (pregnancy status, eating-pattern screen) | Deciding what the program may safely show you; can hide all numbers | Yes |
| Food journal (logged meals, nutrition estimates, your edits) + meal photo thumbnails | Daily totals, the journal, restoring on a new device | Yes |
| Sleep, stress, appetite, and support answers | Pacing your plan honestly | On-device only |
| Messages you write to jeni (the in-app coach) | Generating the coach's reply (see "Coach conversations") | No, stored on-device |
| Notification opt-ins + reminder time | Scheduling local reminders | On-device only |
| Subscription state (RevenueCat customer ID, entitlement) | Unlocking the program | Yes |

### Coach conversations

Messages you send to jeni, plus the program context needed to answer
well (your plan, recent trend, day state, and coarse signals such as
your medication cadence or cycle season), are processed by OpenAI via
our server function to generate replies. Message content is stored on
your device, not in our cloud database. Under our API agreement the
provider does not use these conversations to train its models.

Replies are generated by a language model. They can be wrong, and they
are not medical advice. See the Terms for the full health and safety
disclaimer.

We do not collect: contacts, microphone audio, location, browsing
history outside the app.

## Your care team (clinic-connected features)

Jeni can connect to a participating weight-management practice. **This
is off unless you turn it on.** Nothing about a clinic exists in your
account until you enter an invite code from that practice and accept.

When you connect, you choose which of three consents to grant, and you
can revoke any of them, or disconnect entirely, from Settings →
your care team:

| Consent | What the practice can then see or do |
| --- | --- |
| Your visit packet | The 4-week summary you already prepare for a visit: dose adherence counts, weigh-in count and direction, symptoms you logged, days logged and protein days met, movement days and step average, plus your questions and gaps |
| Your daily records | Your dose marks, how meals sat, hydration, and weigh-ins |
| Your care plan | Lets the practice set the medication plan and protocol your app then follows |

Notes that matter:

- **Access is enforced at the database, not just in the app.** Row-Level
  Security requires an active, unrevoked consent for the practice to
  read your rows or for your device to publish to them.
- **Revoking stops future sharing.** Records the practice already
  received remain in that practice's own records, and how they handle
  them is governed by that practice's privacy notice and by the laws
  that apply to it, not by this policy.
- **Your photos are never shared with a practice.** Neither meal
  thumbnails nor body scans are part of any care scope.
- **A practice never sees your coach conversations.**

### How health-privacy law applies

We are giving you facts, not a legal conclusion. bay82 Studio LLC is
not a healthcare provider, health plan, or healthcare clearinghouse,
and in the direct-to-consumer app we are not acting as one, so the
consumer Jeni service is generally not covered by HIPAA. A clinic you
connect to may itself be a HIPAA-covered entity, and different
obligations can apply to that relationship. If you have questions
about how your practice handles what it receives, ask the practice.

## Analytics and advertising attribution

- **PostHog (product analytics).** We record product events keyed to
  your account id: onboarding steps, screens opened, features used,
  purchase funnel outcomes, and coarse program signals (for example,
  whether a dose was marked taken or skipped, or that a milestone was
  reached). Payloads are restricted to counts, choices, and fixed
  categorical words by a validator that runs on every event. We do not
  send your weight numbers, meals, photos, messages, doses, product
  names, or Apple Health values to analytics.
- **TikTok Business SDK (ad attribution).** Reports app install,
  launch, retention, and purchase events to TikTok so we can measure
  whether our ads work. iOS's App Tracking Transparency prompt
  controls whether this uses your device's advertising identifier
  (IDFA); if you tap "Ask App Not to Track", it does not. No health
  data, no food data, no medication data, and no in-app answers are
  ever sent to TikTok.
- We do not use Firebase, Crashlytics, Amplitude, Mixpanel, Segment,
  Google Analytics, Meta Pixel, or the Meta SDK.

**A hard boundary we hold:** health information (weight, medication,
doses, symptoms, Apple Health values, food logs, photos, and anything
about a clinic relationship) is never sent to advertising or
audience-building systems, and is never used for behavioral targeting.
Ad measurement receives install, launch, retention, and purchase
events only.

## Where it's stored

- **On your device** in the app's sandboxed storage.
- **In the cloud** at [Supabase](https://supabase.com) (managed
  Postgres). Each row is keyed to your auth user id; Row-Level
  Security enforces that you can only reach your own rows.
- **Meal photo thumbnails** (and body scans only if you opted into
  backup) in private Supabase Storage buckets under your user id.
- **At RevenueCat** for subscription state, keyed to your user id.
- **At Apple** if you sign in with Apple.

## Who can see it

Apart from you and Apple's iOS systems on your device:

- The operator of bay82 Studio LLC has read-only access to Supabase
  for support and debugging. We don't browse routinely; we look only
  if you write in.
- A healthcare practice you have connected to, limited to the
  consents you granted (see "Your care team").
- Apple, for Sign in with Apple identifier mapping (we never receive
  your real email if you use Hide My Email).
- Service providers listed below, each receiving only what its job
  needs.

We do not sell or rent your personal data, and we do not disclose
health information for anyone else's advertising. Because the TikTok
ad-measurement events described above can involve your advertising
identifier when you allow tracking, some state privacy laws may treat
that as "sharing" for cross-context behavioral advertising; declining
the iOS tracking prompt, or turning tracking off later in iOS
Settings, stops it.

## Service providers (third parties)

| Provider | What they get | Why |
| --- | --- | --- |
| Supabase | Auth tokens, your synced rows, your photo thumbnails | Database + auth + storage |
| OpenAI | Meal/label photos, and coach messages with program context, transiently | Nutrition estimation; coach replies |
| Open Food Facts | The barcode number you scan | Packaged-food nutrition lookup |
| USDA FoodData Central | Food names being looked up | Nutrition reference data |
| RevenueCat | Customer id, purchase events | Subscription billing state |
| PostHog | Product usage events (see Analytics) | Understanding + improving the app |
| TikTok | Install/launch/retention/purchase events; IDFA only with your ATT consent | Ad measurement |
| Apple (Sign in with Apple) | Apple-issued identifier | Sign-in option |

Notifications are scheduled locally with iOS itself, so no data leaves
your device for reminders.

## Your rights

- **See or update your data.** Your numbers are editable in the app;
  your journal is yours to edit or delete entry by entry.
- **Export.** Email [support@jenifit.app](mailto:support@jenifit.app)
  for a JSON export of your synced rows.
- **Delete your account.** Settings → account → delete account
  permanently deletes your rows from Supabase, your photos from cloud
  storage, and the local data on your device. No soft-delete; the
  data is unrecoverable.
- **Disconnect a clinic.** Settings → your care team → revoke a
  consent or disconnect entirely.
- **Withdraw tracking consent.** iOS Settings → Privacy & Security →
  Tracking, anytime.

If you live in the EU, UK, California, or another jurisdiction with
specific privacy rights, the steps above give effect to those rights.
Contact us for a formal access or portability response.

## Children

Jeni is not directed at children under 13 (or 16 in the EU). If you
believe a child has signed up, contact us and we'll delete the
account.

## Security

- TLS 1.2+ in transit for every connection the app makes.
- Postgres Row-Level Security on every table; private storage buckets
  with per-account access rules.
- Sessions live in the iOS Keychain. No long-lived service
  credentials ship in the app, only publishable keys scoped by
  server-side rules.

## Changes to this policy

Material changes bump the "Last updated" date and (for non-trivial
changes) surface an in-app notice.

## Contact

bay82 Studio LLC
[support@jenifit.app](mailto:support@jenifit.app)
