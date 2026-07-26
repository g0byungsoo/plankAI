# JeniFit — Privacy Policy

**Effective:** 2026-05-08
**Last updated:** 2026-07-25

This policy explains what JeniFit ("we", "us", "the app") collects, why,
where it's stored, who can see it, and how to delete it. We aimed for
plain language. If something's unclear, email
[support@jenifit.app](mailto:support@jenifit.app).

## TL;DR

- **Workout camera frames stay on your phone.** They're processed by
  Apple's Vision framework on-device for plank-form analysis. Frames
  are never saved, recorded, or uploaded.
- **Meal photos you snap** are analyzed to estimate the plate's
  nutrition. A small thumbnail of each meal photo is kept with your
  food journal — on your device and in your private cloud space (see
  "Meal photos" below) — so your journal survives a reinstall or a new
  phone. Only your signed-in account can access your photos, and they
  are deleted when you delete an entry or your account.
- **The data we sync** (your profile, weight logs, session results,
  food journal + meal photo thumbnails) is stored at Supabase under
  your account. You can delete it from Settings → Account → Delete
  Account at any time.
- **No advertising trackers, no third-party analytics.** We don't sell,
  share, or rent your data. The only third parties that touch it are
  the ones listed under "Service providers" below — and only the data
  needed to run the app.

## What we collect

### From the app, locally on your device

- **Camera video frames** during plank check-in sessions. Processed
  in-memory by Apple's Vision framework to detect body pose and form
  faults. Frames are never written to disk, photo library, or our
  servers.
- **Meal photos** when you use the food camera. See "Meal photos"
  below for exactly what's kept and where.
- **Microphone access:** none. The app plays audio but does not record.
- **Photo library access:** none.
- **Location:** none.

### Meal photos

When you snap a plate with the food camera, the photo is sent to our
secure server function to estimate the meal's nutrition. What we keep
afterward:

- **A small thumbnail** (~40KB, long edge capped at 480px — not the
  full camera frame) is stored with the journal entry on your device
  and uploaded to your private space in our cloud storage, so your
  meal photos come back when you reinstall or switch phones.
- **Access is per-account.** The storage bucket is private (nothing is
  publicly reachable), and access rules enforce that only your
  signed-in account can read, write, or delete objects under your own
  folder — the same row-level model as the rest of your data.
- **Deleting follows you everywhere.** Deleting a journal entry
  removes its thumbnail from your device and from cloud storage.
  Deleting your account removes all of your meal photos along with
  everything else.
- We never use your meal photos for advertising, never share them with
  other users, and never train models on them.

### From you, when you create an account or use the app

We collect what you tell us during onboarding and as you use the app.
Categories:

| Data | Why |
| --- | --- |
| Name (first, optional) | Greeting + personalization |
| Age range, gender, height | Calibrating workouts and reference body weight for kcal estimates |
| Body type (current / desired, 1–5 scale) | Personalizing the plan |
| Weight logs (current weight, goal weight, history) | Trend chart, goal progress, BMI |
| Body focus + workout style + workout location | Selecting exercises that match your goal |
| Motivation, identity feeling, reward choice, relatability statements | Personalizing copy + adaptive coaching |
| Barriers (time, motivation, etc.) | Adapting session length + softening failure framing |
| Plank baseline + activity level + experience | Choosing your starting difficulty tier |
| Notification opt-in + reminder time + voice preference | Scheduling daily reminders |
| Session logs (workout completions, plank holds, durations, form scores, ratings) | Progress tracking + tier auto-adjustment |
| Food journal (logged meals, nutrition estimates) + meal photo thumbnails | Food log timeline, daily totals, restoring your journal on a new device |
| Trial / subscription state (RevenueCat customer ID, entitlement) | Gating premium features |

We do not collect:

- Contacts, microphone audio, location, photo library content.
- Browsing history outside the app.
- Device identifiers for tracking purposes (`IDFA` is not requested).

## Where it's stored

- **On your device** in a SwiftData store, in the app's sandboxed
  Application Support directory.
- **In the cloud** at [Supabase](https://supabase.com) (a third-party
  managed Postgres service). Each row is keyed to your auth user id,
  and Postgres Row-Level Security policies enforce that you can only
  read or write your own rows.
- **Meal photo thumbnails** in a private Supabase Storage bucket,
  under a folder named by your auth user id. The same per-account
  access rules apply: only your signed-in session can read, write, or
  delete your photos, and nothing in the bucket is publicly reachable.
- **At RevenueCat** for subscription state, keyed to your auth user id.
- **At Apple** if you signed in with Apple ID.

## Who can see it

Apart from you and Apple's iOS systems on your device:

- The JeniFit operator (Byungsoo Ko) has read-only access to Supabase
  for support and debugging. We don't browse routinely; we look only
  if you write in.
- Apple, for Sign in with Apple identifier mapping (we never receive
  your real Apple ID email if you use Hide My Email).
- Service providers listed below.

We do not sell, share, or rent your personal data.

## Service providers (third parties)

The minimal set we need to run the app:

| Provider | What they get | Why | Where to learn more |
| --- | --- | --- | --- |
| Supabase | Authentication tokens, your synced rows, your meal photo thumbnails | Database + auth + file storage backend | [supabase.com/privacy](https://supabase.com/privacy) |
| Apple (Sign in with Apple) | Apple-issued user identifier (and email if you choose to share) | Sign-in option | [apple.com/legal/privacy](https://apple.com/legal/privacy) |
| RevenueCat | Anonymized customer ID, purchase events | Subscription billing state | [revenuecat.com/privacy](https://revenuecat.com/privacy) |
| Apple Push Notification service | Local-only daily reminders are scheduled with iOS itself, not pushed from a server. No data leaves your device for notifications. | — | — |

We do **not** use Firebase, Crashlytics, Amplitude, Mixpanel, Segment,
PostHog, Google Analytics, Meta Pixel, TikTok Pixel, or any advertising
SDK.

## Your rights

- **See or update your data.** Edit Profile lets you change your name,
  body focus, session length. Weight logs are editable from the
  becoming tab.
- **Export.** Email [support@jenifit.app](mailto:support@jenifit.app)
  and we'll generate a JSON dump of your synced rows.
- **Delete your account.** Settings → Account → Delete Account
  permanently deletes every row of yours from Supabase (cascade), your
  meal photo thumbnails from cloud storage, and the local data on your
  device. There is no soft-delete; the data is unrecoverable.
- **Withdraw consent.** Stop using the app and delete it from your
  phone. If you want the cloud rows gone too, run Delete Account first.

If you live in the EU, UK, California, or another jurisdiction with
specific privacy rights (GDPR right of erasure, CCPA right to delete,
etc.), the steps above already give effect to those rights. Contact
[support@jenifit.app](mailto:support@jenifit.app) if you'd like a
formal data portability export or a right-of-access response.

## Children

JeniFit is not directed at children under 13 (or 16 in the EU). We
don't knowingly collect data from anyone under those ages. If you
believe a child has signed up, contact us and we'll delete the
account.

## Security

- TLS 1.2+ in transit between the app and Supabase + Apple + RevenueCat.
- Postgres Row-Level Security on every Supabase table — you can't
  read or write rows belonging to another user even if our app code
  had a bug. Policies are versioned in [scripts/rls_policies.sql](https://github.com/...).
- No long-lived service credentials are bundled in the app — only a
  public Supabase anon key, scoped by RLS.

## Changes to this policy

If we make material changes, we'll bump the "Last updated" date above
and (for non-trivial changes) surface an in-app notice on next launch.

## Contact

[support@jenifit.app](mailto:support@jenifit.app)
