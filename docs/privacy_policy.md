<!-- FOUNDER: deploy this to jenifit.app/privacy BEFORE the next App Store
     submission, and re-answer the ASC privacy nutrition label to match
     (tracking = YES via TikTok attribution; health & fitness data linked
     to identity). Counsel review recommended. The previous revision
     denied IDFA/PostHog/TikTok while the shipped binary uses them —
     that contradiction is an App Review rejection risk and must not
     stay live. -->

# Jeni — Privacy Policy

**Effective:** 2026-05-08
**Last updated:** 2026-08-08

Jeni (formerly JeniFit — "we", "us", "the app") is a weight-care
program. This policy explains what we collect, why, where it's stored,
who can see it, and how to delete it. We aimed for plain language. If
something's unclear, email
[support@jenifit.app](mailto:support@jenifit.app).

## TL;DR

- **Your account works anonymously.** You can use the whole app
  without giving us an email; sign-in (Apple or email) is optional and
  exists so your data can follow you to a new phone.
- **Meal photos you snap** are sent to our server function and analyzed
  by a vision model (OpenAI or Anthropic) to estimate nutrition. The
  full-size photo is processed and discarded; a small thumbnail is
  kept with your food journal — on your device and in your private
  cloud space — unless you turn that off in Settings → privacy.
- **Body scan photos never leave your phone** unless you explicitly
  turn on scan backup (off by default). No number is ever derived
  from a body photo.
- **Apple Health data stays out of our cloud.** Steps, sleep, and
  weight readings you grant access to are used on-device to run your
  plan. We never sell it, never use it for advertising, and never
  send it to advertising partners.
- **We use analytics and ad attribution.** PostHog measures how the
  app is used (screens, funnel steps, purchases — never your meals,
  weights, messages, or photos). The TikTok Business SDK reports
  install and purchase events so we can measure our ads; it can only
  use your device's advertising identifier if you allow tracking in
  the iOS prompt.
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
- **Apple Health (HealthKit)** — only what you grant: steps, sleep,
  body weight, and related vitals. Read on-device to compose your
  day, chart your trend, and import weigh-ins passively. The app can
  also write the nutrition you log to Apple Health if you allow it.
  HealthKit data is not uploaded to our servers and is never used
  for advertising or shared with advertising partners.
- **Microphone:** none. **Location:** none. **Photo library:** we
  never read your library; if you save a share card, iOS asks for
  add-only permission.

### Meal photos

When you snap a plate (or a nutrition label), the photo is sent to our
secure server function, which passes it to a vision model provider
(OpenAI or Anthropic) to estimate the meal's nutrition. Under our API
agreements these providers do not use your photos to train their
models. What we keep afterward:

- **A small thumbnail** (long edge capped at 480px — not the full
  camera frame) is stored with the journal entry on your device and
  uploaded to your private space in our cloud storage, so your meal
  photos come back when you reinstall or switch phones. The full-size
  photo is not stored.
- **You can turn photo keeping off.** Settings → privacy → photo
  retention: choose "discard after analysis" and no photo is saved to
  your journal or uploaded — only the nutrition estimate is kept.
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

| Data | Why |
| --- | --- |
| Name (first, optional) | Greeting + personalization |
| Age range, gender, height | Calorie targets and pacing (published equations) |
| Weight logs (current, goal, history — typed or imported from Apple Health) | Trend chart, goal pace, plan recalibration |
| Weight-medication status (e.g. whether you're on a GLP-1 medication, your dose day if you choose to share it) | Composing your day around your medication rhythm; protein and muscle-preservation targets |
| Safety screening answers (pregnancy status, eating-pattern screen) | Deciding what the program may safely show you; can hide all numbers |
| Food journal (logged meals, nutrition estimates, your edits) + meal photo thumbnails | Daily totals, the journal, restoring on a new device |
| Sleep, stress, appetite, and support answers | Pacing your plan honestly |
| Messages you write to jeni (the in-app coach) | Generating the coach's reply (see "Coach conversations") |
| Notification opt-ins + reminder time | Scheduling local reminders |
| Subscription state (RevenueCat customer ID, entitlement) | Unlocking the program |

### Coach conversations

Messages you send to jeni, plus the program context needed to answer
well (your plan, recent trend, day state), are processed by OpenAI via
our server function to generate replies. Message content is stored on
your device, not in our cloud database. Under our API agreements the
provider does not use these conversations to train its models.

We do not collect: contacts, microphone audio, location, browsing
history outside the app.

## Analytics and advertising attribution

- **PostHog (product analytics).** We record product events keyed to
  your account id — onboarding steps, screens opened, features used,
  purchase funnel outcomes, and coarse program signals (for example,
  your medication cohort and whether a milestone was reached). We do
  not send your weight numbers, meals, photos, messages, or Apple
  Health values to analytics.
- **TikTok Business SDK (ad attribution).** Reports app install,
  launch, retention, and purchase events to TikTok so we can measure
  whether our ads work. iOS's App Tracking Transparency prompt
  controls whether this uses your device's advertising identifier
  (IDFA); if you tap "Ask App Not to Track", it does not. No health
  data, no food data, and no in-app answers are ever sent to TikTok.
- We do not use Firebase, Crashlytics, Amplitude, Mixpanel, Segment,
  Google Analytics, or Meta Pixel.

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

- The Jeni operator (Byungsoo Ko) has read-only access to Supabase for
  support and debugging. We don't browse routinely; we look only if
  you write in.
- Apple, for Sign in with Apple identifier mapping (we never receive
  your real email if you use Hide My Email).
- Service providers listed below, each receiving only what its job
  needs.

We do not sell or rent your personal data.

## Service providers (third parties)

| Provider | What they get | Why |
| --- | --- | --- |
| Supabase | Auth tokens, your synced rows, your photo thumbnails | Database + auth + storage |
| OpenAI | Meal/label photos and coach messages (with program context), transiently | Nutrition estimation; coach replies |
| Anthropic | Meal/label photos, transiently | Nutrition estimation |
| Open Food Facts | The barcode number you scan | Packaged-food nutrition lookup |
| USDA FoodData Central | Food names being calibrated | Nutrition reference data |
| RevenueCat | Customer id, purchase events | Subscription billing state |
| PostHog | Product usage events (see Analytics) | Understanding + improving the app |
| TikTok | Install/launch/retention/purchase events; IDFA only with your ATT consent | Ad measurement |
| Apple (Sign in with Apple) | Apple-issued identifier | Sign-in option |

Notifications are scheduled locally with iOS itself — no data leaves
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
  credentials ship in the app — only publishable keys scoped by
  server-side rules.

## Changes to this policy

Material changes bump the "Last updated" date and (for non-trivial
changes) surface an in-app notice.

## Contact

[support@jenifit.app](mailto:support@jenifit.app)
